-- Lot RANGEES-ASM : règle pure shared/ai3/rangees_asm.lua (agrandir, nouveau, refus) et mutants refusés.
package.path = "./?.lua;" .. package.path
local Ra = require("shared.ai3.rangees_asm")

local ok, ko = 0, 0
local function check(name, cond)
  if cond then ok = ok + 1 else ko = ko + 1 print("ECHEC : " .. name) end
end

-- jeu de cas : (requête, contrôle)
local CASES = {
  { "demande de 5 machines sans rangee : nouvelle rangee de 5", { rate = 600, nom1 = 120, n_max = 6, existing = {} },
    function(d) return d.action == "nouveau" and d.n == 5 and d.near == nil end },
  { "demande de 2 machines : rangee portee a 5", { rate = 200, nom1 = 120, n_max = 6, existing = {} },
    function(d) return d.action == "nouveau" and d.n == 5 and d.k == 2 end },
  { "demande d'une machine : 1 seule", { rate = 60, nom1 = 120, n_max = 6, existing = {} },
    function(d) return d.action == "nouveau" and d.n == 1 end },
  { "borne du gabarit respectee", { rate = 1200, nom1 = 120, n_max = 3, existing = {} },
    function(d) return d.action == "nouveau" and d.n == 3 end },
  { "hausse avec rangee en attente : agrandir", { rate = 240, nom1 = 120, n_max = 6, existing = { { id = 7, n = 2, state = "attente" } } },
    function(d) return d.action == "agrandir" and d.target == 7 and d.from == 2 and d.n == 4 end },
  { "agrandir borne au gabarit", { rate = 1200, nom1 = 120, n_max = 6, existing = { { id = 7, n = 4, state = "attente" } } },
    function(d) return d.action == "agrandir" and d.n == 6 end },
  { "rangee en attente pleine : nouvelle a cote", { rate = 240, nom1 = 120, n_max = 6, existing = { { id = 7, n = 6, state = "attente" } } },
    function(d) return d.action == "nouveau" and d.near == 7 end },
  { "rangee deja batie : nouvelle a cote, jamais loin", { rate = 600, nom1 = 120, n_max = 6, existing = { { id = 9, n = 2, state = "fini" } } },
    function(d) return d.action == "nouveau" and d.near == 9 and d.n == 5 end },
  { "rangee refusee ignoree pour la proximite", { rate = 600, nom1 = 120, n_max = 6, existing = { { id = 3, n = 2, state = "refuse" } } },
    function(d) return d.action == "nouveau" and d.near == nil end },
  { "ordre des ids (pas de pairs) : la plus ancienne en attente", { rate = 120, nom1 = 120, n_max = 6,
      existing = { { id = 12, n = 2, state = "attente" }, { id = 4, n = 1, state = "attente" } } },
    function(d) return d.action == "agrandir" and d.target == 4 end },
  { "refus : debit nominal nul", { rate = 600, nom1 = 0, n_max = 6 }, function(d) return d.action == "refus" and d.why == "debit nominal nul" end },
  { "refus : demande nulle", { rate = 0, nom1 = 120, n_max = 6 }, function(d) return d.action == "refus" and d.why == "demande nulle" end },
  { "refus : gabarit sans borne", { rate = 600, nom1 = 120, n_max = nil }, function(d) return d.action == "refus" and d.why == "gabarit sans borne" end },
}

local function run_cases(R)
  local good = 0
  for _, c in ipairs(CASES) do
    local okc, d = pcall(R.decide, c[2])
    if okc and d and c[3](d) then good = good + 1 end
  end
  return good
end

for _, c in ipairs(CASES) do
  local d = Ra.decide(c[2])
  check(c[1], c[3](d))
end
-- journal
local line = Ra.line("emerald", "objet-x", 600, Ra.decide(CASES[1][2]))
check("ligne [FO-RANGEES-ASM]", line:find("^%[FO%-RANGEES%-ASM%] emerald : objet%-x 600/min %-> nouveau a 5 machine") ~= nil)
-- pas de nom d'objet en dur, pas de pairs dans la règle
local fh = io.open("shared/ai3/rangees_asm.lua", "rb")
local src = fh:read("*a") fh:close()
check("aucun pairs dans la regle", not src:find("pairs%(") or not src:gsub("ipairs%(", ""):find("pairs%("))
check("aucun nom d'objet en dur", not src:find("copper") and not src:find("cable") and not src:find("iron"))

-- mutants : chacun doit faire échouer au moins un cas
local MUTANTS = {
  { "MIN_ROW = 1", function(M) M.MIN_ROW = 1 end },
  { "JUSTIFY = 99 (jamais de rangee de 5)", function(M) M.JUSTIFY = 99 end },
  { "aucun etat agrandissable", function(M) M.GROWABLE = {} end },
  { "agrandir meme une rangee batie", function(M) M.GROWABLE = { attente = true, fini = true } end },
  { "decide sans borne", function(M) local d0 = M.decide M.decide = function(q) local q2 = {} for k, v in pairs(q) do q2[k] = v end q2.n_max = 99 return d0(q2) end end },
  { "decide sans proximite", function(M) local d0 = M.decide M.decide = function(q) local d = d0(q) d.near = nil return d end end },
  { "toujours nouveau", function(M) local d0 = M.decide M.decide = function(q) local d = d0(q) if d.action == "agrandir" then d.action = "nouveau" end return d end end },
}
local base = run_cases(Ra)
check("temoin : tous les cas passent", base == #CASES)
for _, mu in ipairs(MUTANTS) do
  package.loaded["shared.ai3.rangees_asm"] = nil
  local M = require("shared.ai3.rangees_asm")
  mu[2](M)
  local good = run_cases(M)
  check("mutant refuse : " .. mu[1], good < #CASES)
end
package.loaded["shared.ai3.rangees_asm"] = nil

print(string.format("[RANGEES-ASM] BILAN : %d OK, %d ECHEC(S)", ok, ko))
os.exit(ko == 0 and 0 or 1)
