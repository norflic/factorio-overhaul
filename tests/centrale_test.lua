--[[
  Tests hors jeu du lot CORR-ENERGIE : croissance de la centrale (shared/team/centrale.lua), avec mutants.
  Usage :   lua5.2 tests/centrale_test.lua
]]
package.path = "./?.lua;" .. package.path
local M = require("shared.team.modules")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
end
local function section(name) if not quiet then print("== " .. name) end end

local CAP = 2 * M.BASE["steam-engine"].power_out * 1000 / 60 -- une chaudière, deux machines : 30 000 J/tick

--- Batterie de contrôles sur un module C (le vrai ou un mutant).
local function battery(C)
  local function free() return { done = 1, pending = 0, refused = 0, hold = false, off = false } end
  section("1. Saturation")
  local st = {}
  for _ = 1, 5 do C.observe(st, 0.85 * CAP, CAP) end
  check(not st.saturated, "pas saturee avant 6 releves de 5 s (30 s)")
  C.observe(st, 0.85 * CAP, CAP)
  check(st.saturated, "saturee au 6e releve (30 s)")
  C.observe(st, 0.5 * CAP, CAP)
  check(not st.saturated and st.sat == 0, "un releve sous 80 % remet le compte a zero")
  local s2 = {}
  for _ = 1, 6 do C.observe(s2, 0.8 * CAP, CAP) end
  check(s2.saturated, "exactement 80 % compte comme sature")
  local s3 = {}
  for _ = 1, C.SAT_CHECKS + 5 do C.observe(s3, 0.79 * CAP, CAP) end
  check(not s3.saturated, "79 % ne sature pas")
  local s4 = {}
  for _ = 1, 10 do C.observe(s4, 0, CAP) end
  check(not s4.saturated, "production nulle (panne) : jamais saturee")
  local s5 = {}
  for _ = 1, 10 do C.observe(s5, 100, 0) end
  check(not s5.saturated, "capacite nulle : jamais saturee")
  local s6 = {}
  for _ = 1, C.SAT_CHECKS do C.observe(s6, CAP, CAP) end
  check(s6.saturated, "100 % de la capacite : saturee")

  section("2. Croissance")
  local s = { saturated = true }
  check(C.growth(s, free()) == C.BOILERS and C.BOILERS == 1, "saturee, centrale finie : UNE chaudiere de plus")
  local n = free(); n.done = 2
  check(C.growth(s, n) == 1, "deux centrales finies : une troisieme possible")
  n = free(); n.pending = 1
  check(C.growth(s, n) == nil, "un chantier de centrale ouvert : on attend")
  n = free(); n.done = C.MAX_PLANTS
  check(C.growth(s, n) == nil, "plafond de centrales")
  n = free(); n.done = C.MAX_PLANTS - 1
  check(C.growth(s, n) == 1, "sous le plafond : permis")
  n = free(); n.done = 0
  check(C.growth(s, n) == nil, "aucune centrale finie : rien a faire grandir")
  n = free(); n.refused = C.MAX_REFUSED
  check(C.growth(s, n) == nil, "plan refuse deux fois : on cesse d'insister")
  n = free(); n.refused = C.MAX_REFUSED - 1
  check(C.growth(s, n) == 1, "un seul refus : on reessaie")
  n = free(); n.hold = true
  local nb, why = C.growth(s, n)
  check(nb == nil and why ~= nil, "repli de l'equipe (manque de matiere) : rien, avec une raison")
  n = free(); n.off = true
  check(C.growth(s, n) == nil, "regle coupee par le reglage de banc : rien")
  check(C.growth({ saturated = false }, free()) == nil, "non saturee : rien")
  check(C.growth({}, free()) == nil, "jamais releve : rien")
  local s7 = { saturated = true, sat = 9 }
  C.requested(s7)
  check(C.growth(s7, free()) == nil and s7.sat == 0, "apres la demande : a remesurer")

  n = free(); n.cool = true
  nb, why = C.growth(s, n)
  check(nb == nil and why ~= nil, "pause apres une centrale abandonnee : rien")
  local s8 = { saturated = true, requests = C.MAX_REQUESTS - 1 }
  check(C.growth(s8, free()) == 1, "derniere demande permise")
  s8.requests = C.MAX_REQUESTS
  check(C.growth(s8, free()) == nil, "borne des demandes sur la partie : rien")
  C.requested(s8)
  check(s8.requests == C.MAX_REQUESTS + 1, "chaque demande est comptee")

  section("2 bis. Reserve abandonnee (crise de matiere)")
  check(C.stale("reserve", "materiaux", C.STALE) == true, "reserve incomplete depuis 30 min : abandon")
  check(C.stale("reserve", "materiaux", C.STALE - 1) == false, "pas encore 30 min : on attend")
  check(C.stale("reserve", nil, C.STALE * 3) == false, "reserve sans manque : jamais abandonnee")
  check(C.stale("chantier", "materiaux", C.STALE * 3) == false, "en chantier : jamais abandonnee")
  check(C.stale("attente", "materiaux", C.STALE * 3) == false, "en attente de plan : jamais abandonnee")

  section("3. Plafond jamais depasse en simulation")
  local sim, done, pending, asked = { }, 1, 0, 0
  for step = 1, 400 do
    -- charge constante de 6 MW : toujours saturee tant que la capacite ne la couvre pas
    local cap = CAP * done
    C.observe(sim, math.min(cap, 6000 * 1000 / 60), cap)
    local g = C.growth(sim, { done = done, pending = pending, refused = 0, hold = false, off = false })
    if g then asked = asked + 1; pending = pending + 1; C.requested(sim) end
    if pending > 0 and step % 20 == 0 then pending = pending - 1; done = done + 1 end
  end
  check(done == C.MAX_PLANTS, "6 MW : s'arrete a " .. C.MAX_PLANTS .. " centrales (" .. done .. ")")
  check(asked == C.MAX_PLANTS - 1, "autant de demandes que de centrales de plus (" .. asked .. ")")
end

section("Regle reelle")
local real = require("shared.team.centrale")
battery(real)

section("Le gabarit demande passe le controle")
for nb = 1, 3 do
  local g = M.GEN.steam(nb)
  check(g ~= nil and #M.check(g) == 0, "centrale de " .. nb .. " chaudiere(s) : gabarit valide")
end
check(M.BASE["steam-engine"].power_out == 900, "machine a vapeur : 900 kW lus aux donnees")
check(CAP == 30000, "capacite d'une centrale de base : 30 000 J/tick")

-- Mutants : chacun doit faire echouer au moins un controle de la batterie.
section("Mutants")
local f = assert(io.open("shared/team/centrale.lua", "rb"))
local src = f:read("*a")
f:close()
local mutants = {
  { "seuil 0.8 -> 0.9", "C.SAT = 0.8", "C.SAT = 0.9" },
  { "seuil 0.8 -> 0.5", "C.SAT = 0.8", "C.SAT = 0.5" },
  { "comparaison >= -> >", "power >= C.SAT * capacity", "power > C.SAT * capacity" },
  { "duree 6 -> 1 releve", "C.SAT_CHECKS = 6", "C.SAT_CHECKS = 1" },
  { "duree 6 -> 12 releves", "C.SAT_CHECKS = 6", "C.SAT_CHECKS = 12" },
  { "capacite nulle comptee", "capacity > 0 and power", "power" },
  { "plafond 3 -> 9", "C.MAX_PLANTS = 3", "C.MAX_PLANTS = 9" },
  { "plafond atteint permis (>= -> >)", "n.done >= C.MAX_PLANTS", "n.done > C.MAX_PLANTS" },
  { "chantier ouvert ignore", "if n.pending > 0 then", "if false then" },
  { "refus ignores", "(n.refused or 0) >= C.MAX_REFUSED", "false" },
  { "repli ignore", "if n.hold then", "if false then" },
  { "reglage de banc ignore", "if n.off then", "if false then" },
  { "sans centrale finie", "if n.done < 1 then", "if false then" },
  { "demande sans remise a zero", "st.sat, st.saturated = 0, false", "st.sat = st.sat" },
  { "deux chaudieres", "C.BOILERS = 1 ", "C.BOILERS = 2 " },
  { "relevé sans remise a zero", "else st.sat = 0 end", "end" },
  { "pause apres abandon ignoree", "if n.cool then", "if false then" },
  { "borne des demandes ignoree", "(st.requests or 0) >= C.MAX_REQUESTS", "false" },
  { "demandes non comptees", "st.requests = (st.requests or 0) + 1", "st.requests = st.requests" },
  { "abandon sans delai", "state == \"reserve\" and reason == \"materiaux\" and waited >= C.STALE", "state == \"reserve\" and reason == \"materiaux\"" },
  { "abandon d'un chantier", "state == \"reserve\" and reason", "state ~= \"fini\" and reason" },
}
local refused = 0
for _, m in ipairs(mutants) do
  local a, b = src:find(m[2], 1, true)
  if not a then
    failures = failures + 1
    print("  ECHEC : mutant '" .. m[1] .. "' : motif introuvable dans la source")
  else
    local msrc = src:sub(1, a - 1) .. m[3] .. src:sub(b + 1)
    local chunk, err = load(msrc, "=mutant", "t")
    if not chunk then
      failures = failures + 1
      print("  ECHEC : mutant '" .. m[1] .. "' ne compile pas : " .. tostring(err))
    else
      local ok, mod = pcall(chunk)
      local before = failures
      quiet = true
      local okb = pcall(battery, ok and mod or real)
      quiet = false
      local killed = (failures > before) or not okb
      -- les echecs d'un mutant ne comptent pas comme des echecs du test : on les retire
      failures = before
      if killed then refused = refused + 1; passes = passes + 1 else failures = failures + 1; print("  ECHEC : mutant SURVIVANT : " .. m[1]) end
    end
  end
end
print(string.format("  mutants refuses : %d sur %d", refused, #mutants))

print(string.format("[CENTRALE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
