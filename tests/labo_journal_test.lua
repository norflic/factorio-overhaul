--[[
  Lot BLOCAGE-LABOS : le journal [FO-LABO] (script/ai3/labo_journal.lua) avec des doublures de Stock, General et Pet (noms inventés).
    §1 rien n'attend : aucune ligne ; §2 une recherche qui attend : UNE ligne avec la cause ; §3 même signature : pas de répétition ;
    §4 signature changée avant une minute : pas de ligne, après : une ligne ; §5 levée : une ligne « repart » ; §6 mutants refusés.
  Usage : lua5.2 tests/labo_journal_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("script/ai3/labo_journal.lua")

local ok_n, ko_n = 0, 0
local function check(cond, msg)
  if cond then ok_n = ok_n + 1 else ko_n = ko_n + 1 print("[LABO-JOURNAL] ECHEC " .. msg) end
end

-- Rend le nombre d'échecs de la suite sur la source donnée.
local function suite(src)
  local fails = 0
  local function c(cond) if not cond then fails = fails + 1 end end
  local lines = {}
  local env = setmetatable({ log = function(l) lines[#lines + 1] = l end }, { __index = _G })
  local chests = { ["pk-b"] = 0 }
  local sav = {}
  for _, n in ipairs({ "shared.ai3.labo_cause", "script.team.stock", "script.ai3.general", "script.ai3.petrole" }) do sav[n] = package.loaded[n] end
  package.loaded["shared.ai3.labo_cause"] = nil
  package.loaded["script.team.stock"] = { count = function(_, item) return chests[item] or 0 end }
  package.loaded["script.ai3.general"] = { feasible = function(_, item) if item == "pk-a" then return true end if item == "pk-b" then return false end return nil end }
  package.loaded["script.ai3.petrole"] = { reason_for = function(_, item) return item == "pk-b" and "site 'x' refuse" or nil end }
  local chunk = load(src, "=labo_journal", "t", env)
  local Lj = chunk and select(2, pcall(chunk))
  for n, v in pairs(sav) do package.loaded[n] = v end
  package.loaded["shared.ai3.labo_cause"] = nil
  if type(Lj) ~= "table" then return 999 end
  local f = { key = "fx" }
  local st = {}
  local spec = { ing = { { "pk-a", 1 }, { "pk-b", 1 } } }
  -- §1 rien n'attend
  Lj.note(f, st, "t1", spec, {}, 100, 1.0, false)
  c(#lines == 0)
  -- §2 attend : une ligne
  Lj.note(f, st, "t1", spec, {}, 4000, 1.1, true)
  c(#lines == 1 and lines[1]:find("[FO-LABO] fx", 1, true) and lines[1]:find("pack pk-b ni en stock ni fabricable (site 'x' refuse)", 1, true)
    and lines[1]:find("pack pk-a fabricable, attendu (0/1)", 1, true))
  -- §3 même signature, une minute plus tard : rien
  Lj.note(f, st, "t1", spec, {}, 4000 + 3700, 2.0, true)
  c(#lines == 1)
  -- §4 signature changée (pk-a arrive) AVANT une minute : rien ; APRÈS : une ligne
  chests["pk-a"] = 1
  Lj.note(f, st, "t1", spec, {}, 4000 + 100, 1.2, true)
  c(#lines == 1)
  Lj.note(f, st, "t1", spec, {}, 4000 + 3600, 2.0, true)
  c(#lines == 2 and not lines[2]:find("pk-a", 1, true))
  -- §5 levée : « repart » après la minute, une seule fois
  Lj.note(f, st, "t1", spec, {}, 4000 + 3600 + 10, 2.1, false)
  c(#lines == 2)
  Lj.note(f, st, "t1", spec, {}, 4000 + 7300, 3.0, false)
  c(#lines == 3 and lines[3]:find("repart", 1, true))
  Lj.note(f, st, "t1", spec, {}, 4000 + 14000, 4.0, false)
  c(#lines == 3)
  -- la liste rendue
  local l = Lj.note(f, { }, "t2", spec, {}, 9000, 5.0, true)
  c(type(l) == "table" and #l == 2)
  return fails
end

check(suite(SRC) == 0, "la suite passe sur la source")
local MUT = {
  { "tick - lg.tick >= Lj.EVERY then\n    lg.sig, lg.tick = sig, tick", "true then\n    lg.sig, lg.tick = sig, tick" },
  { "if sig ~= lg.sig and", "if true and" },
  { "if lg.sig ~= \"\" and tick - lg.tick >= Lj.EVERY then", "if tick - lg.tick >= Lj.EVERY then" },
  { "lg.sig, lg.tick = \"\", tick", "lg.tick = tick" },
  { "Lj.EVERY = 3600", "Lj.EVERY = 0" },
  { "if not blocked then", "if blocked then" },
  { "stock[ing[1]] = Stock.count(f, ing[1])", "stock[ing[1]] = 0" },
}
local refused = 0
for i, m in ipairs(MUT) do
  local a, b = SRC:find(m[1], 1, true)
  if not a then check(false, "mutant " .. i .. " : motif absent")
  else
    local killed = suite(SRC:sub(1, a - 1) .. m[2] .. SRC:sub(b + 1)) ~= 0
    if killed then refused = refused + 1 end
    check(killed, "mutant " .. i .. " NON refusé : " .. m[1])
  end
end
print(string.format("[LABO-JOURNAL] mutants refusés : %d sur %d", refused, #MUT))
print(string.format("[LABO-JOURNAL] BILAN : %d OK, %d ECHEC(S)", ok_n, ko_n))
os.exit(ko_n == 0 and 0 or 1)
