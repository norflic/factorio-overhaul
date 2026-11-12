--[[
  Lot TAPIS-MANQUANTS (12/11) : le RÉSEAU DU CHARBON d'une bande de champ (projet à part, lot FONDERIE ; script/team/migration_champ.lua,
  coal_projects et defer_projects) n'était le but d'aucun cerveau : Mig.projects ne rend que les bandes (créneaux, bandes en avance). Ses
  tapis n'arrivaient que par la remise directe des kits fabriqués pour d'AUTRES projets (script/ai3/amorce_rt.lua, AmRt.deliver) :
  scarlet, graine 2507543475, projet 7 en « reserve:materiaux » 0/122 de 14 à 60 min, 23 fours de la bande sans charbon.
  Règle pure : shared/team/champ_lien.lua, Ln.coal_feeds ; branchée par script/ai3/automatisation.lua (but « auto:champ-charbon »).
  Lancement : lua5.2 tests/champ_charbon_but_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Ln = require("shared.team.champ_lien")

local function read(p)
  local fh = assert(io.open(p, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end

local n_ok, n_ko = 0, 0
local function check(c, what)
  if c then n_ok = n_ok + 1 else n_ko = n_ko + 1; print("ECHEC : " .. what) end
end

local function same(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end

-- liste { { id, state, coal } } -> (order, projects) du plan directeur ; coal nil : une bande
local function plan_of(list)
  local order, projects = {}, {}
  for _, it in ipairs(list) do
    order[#order + 1] = it.id
    projects[it.id] = { state = it.state, spec = { site = "champ", champ = { oid = 3, pr = -349, coal = it.coal } } }
  end
  return order, projects
end

local function run(M)
  local r = {}
  if type(M.coal_feeds) ~= "function" then return r end
  local function feeds(list) return M.coal_feeds(plan_of(list)) end
  -- scarlet, graine 2507543475, 14 min : bande 6 (en chantier), réseau du charbon 7 (réserve), bande 9 (fini)
  r.c1 = same(feeds({ { id = 6, state = "chantier" }, { id = 7, state = "reserve", coal = 1 }, { id = 9, state = "fini" } }), { 7 })
  -- réseau fini ou refusé : plus de but ; les deux côtés d'une bande, et un lié (link) : tous servis, dans l'ordre du plan directeur
  r.c2 = same(feeds({ { id = 3, state = "fini", coal = 1 }, { id = 4, state = "refuse", coal = -1 } }), {})
  r.c3 = same(feeds({ { id = 12, state = "reserve", coal = -1 }, { id = 5, state = "chantier", coal = 1 }, { id = 8, state = "fantomes", coal = 1 } }),
    { 12, 5, 8 })
  -- une bande (coal nil) n'est jamais rendue : elle a son but par Mig.projects ; un projet hors champ non plus
  r.c4 = same(feeds({ { id = 2, state = "reserve" } }), {}) and same(M.coal_feeds({ 1 }, { [1] = { state = "reserve", spec = {} } }), {})
  r.c5 = same(M.coal_feeds(nil, nil), {})
  return r
end

local x = run(Ln)
check(x.c1, "le reseau du charbon en reserve est un but (scarlet, projet 7)")
check(x.c2, "reseau fini ou refuse : aucun but")
check(x.c3, "tous les reseaux vivants, dans l'ordre du plan directeur")
check(x.c4, "une bande n'est pas rendue (Mig.projects la sert)")
check(x.c5, "liste absente : aucun but")

-- câblage : l'automatisation fait un but par réseau du charbon, de ses manques (Build.brief)
local S = read("script/ai3/automatisation.lua")
check(S:find("Ln.coal_feeds(f.build and f.build.order, f.build and f.build.projects)", 1, true) ~= nil and S:find("\"champ-charbon\"", 1, true) ~= nil,
  "script/ai3/automatisation.lua : un but auto:champ-charbon par reseau du charbon")

-- mutants
local src = read("shared/team/champ_lien.lua")
local muts = {
  { "bandes aussi rendues", "cs.coal ~= nil and", "" },
  { "fini garde", "Ln.FED[q.state]", "q.state ~= \"refuse\"" },
  { "refuse garde", "Ln.FED[q.state]", "q.state ~= \"fini\"" },
}
local caught = 0
for _, m in ipairs(muts) do
  local s2, n = src:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")), 1)
  assert(n == 1, "mutant introuvable : " .. m[1])
  local M = assert(load(s2))()
  local y = run(M)
  if not (y.c1 and y.c2 and y.c3 and y.c4 and y.c5) then caught = caught + 1 else print("mutant survivant : " .. m[1]) end
end
check(caught == #muts, string.format("mutants tues %d/%d", caught, #muts))

print(string.format("champ_charbon_but_test : %d OK, %d echec(s)", n_ok, n_ko))
if n_ko > 0 then os.exit(1) end
