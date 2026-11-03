--[[
  Revue-fonderie, point 7 (3/11) : lecteur des projets LIÉS du réseau du charbon (shared/team/champ_lien.lua ; branché par
  script/team/champ.lua, Champ.links_step, appelé par Champ.report). Lancement : lua5.2 tests/champ_lien_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Ln = require("shared.team.champ_lien")

local okc, fail = 0, 0
local function check(c, msg) if c then okc = okc + 1 else fail = fail + 1; print("ECHEC : " .. msg) end end
local function same(a, b) if #a ~= #b then return false end for i = 1, #a do if a[i] ~= b[i] then return false end end return true end

local function run(L)
  local r = {}
  -- 1. bande refusée : son projet lié en réserve est annulé, celui déjà en chantier non (il n'est pas annulable)
  local a = L.decide({ { id = 20, state = "reserve", band = 10, side = 1, band_state = "refuse" },
    { id = 21, state = "chantier", band = 10, side = -1, band_state = "refuse" } })
  r.c1 = same(a.cancel, { 20 }) and #a.rerequest == 0
  -- 2. bande absente du plan directeur (nil) : projet lié en attente annulé
  local b = L.decide({ { id = 30, state = "attente", band = 11, side = 1, band_state = nil } })
  r.c2 = same(b.cancel, { 30 })
  -- 3. bande vivante, projet lié refusé (un seul) : redemandé
  local c = L.decide({ { id = 40, state = "refuse", band = 12, side = -1, band_state = "chantier" } })
  r.c3 = same(c.rerequest, { 40 }) and #c.cancel == 0
  -- 4. bande vivante, un refusé ET un vivant pour ce côté : rien (déjà redemandé)
  local d = L.decide({ { id = 50, state = "refuse", band = 13, side = 1, band_state = "fini" }, { id = 51, state = "reserve", band = 13, side = 1, band_state = "fini" } })
  r.c4 = #d.rerequest == 0 and #d.cancel == 0
  -- 5. plafond : 3 refusés pour (bande, côté) : plus rien ; 2 refusés : le DERNIER est redemandé
  local e = L.decide({ { id = 60, state = "refuse", band = 14, side = 1, band_state = "fini" }, { id = 61, state = "refuse", band = 14, side = 1, band_state = "fini" },
    { id = 62, state = "refuse", band = 14, side = 1, band_state = "fini" } })
  local e2 = L.decide({ { id = 71, state = "refuse", band = 15, side = 1, band_state = "fini" }, { id = 70, state = "refuse", band = 15, side = 1, band_state = "fini" } })
  r.c5 = #e.rerequest == 0 and same(e2.rerequest, { 71 })
  -- 6. deux côtés d'une même bande vivante : chacun jugé à part
  local g = L.decide({ { id = 80, state = "refuse", band = 16, side = 1, band_state = "fini" }, { id = 81, state = "fini", band = 16, side = -1, band_state = "fini" } })
  r.c6 = same(g.rerequest, { 80 })
  -- 7. projet lié vivant, bande vivante : rien
  local h = L.decide({ { id = 90, state = "fini", band = 17, side = 1, band_state = "fini" } })
  r.c7 = #h.cancel == 0 and #h.rerequest == 0
  -- 8. déterminisme : ordre des entrées sans effet, sorties triées
  local i1 = L.decide({ { id = 102, state = "plan", band = 19, side = 1, band_state = "refuse" }, { id = 101, state = "reserve", band = 18, side = 1, band_state = "refuse" } })
  local i2 = L.decide({ { id = 101, state = "reserve", band = 18, side = 1, band_state = "refuse" }, { id = 102, state = "plan", band = 19, side = 1, band_state = "refuse" } })
  r.c8 = same(i1.cancel, { 101, 102 }) and same(i2.cancel, { 101, 102 })
  r.empty = #L.decide({}).cancel == 0 and #L.decide(nil).rerequest == 0
  return r
end

local r = run(Ln)
check(r.c1, "bande refusee : projet lie en reserve annule, celui en chantier garde")
check(r.c2, "bande absente : projet lie en attente annule")
check(r.c3, "bande vivante, projet lie refuse : redemande")
check(r.c4, "un projet lie vivant pour ce cote : rien a redemander")
check(r.c5, "plafond de 3 refus ; sous le plafond, le dernier refuse est redemande")
check(r.c6, "chaque cote juge a part")
check(r.c7, "rien a faire quand tout vit")
check(r.c8, "deterministe, sorties triees")
check(r.empty, "aucune entree : rien")
check(Ln.MAX_TRIES == 3, "plafond 3")

-- branchement (lecture des sources)
local function read(p) local h = assert(io.open(p, "r")); local s = h:read("*a"); h:close(); return s end
local S = read("script/team/champ.lua")
check(S:find("local acts = Ln.decide(items)", 1, true) ~= nil and S:find("Build.cancel(f, id, \"champ: bande liee absente ou refusee\")", 1, true) ~= nil
  and S:find("local nid = Build.request(f, spec)", 1, true) ~= nil, "Champ.links_step : decision, annulation, nouvelle demande")
check(S:find("Champ.links_step(f, tick) -- (revue-fonderie, point 7)", 1, true) ~= nil, "Champ.report appelle le lecteur")
check(S:find("pieces ecartees du role %s", 1, true) ~= nil and S:find("common = e.coalnet ~= nil or nil", 1, true) ~= nil, "journal des pieces ecartees par role, charbon commun a part")

-- mutants
local src = read("shared/team/champ_lien.lua")
local muts = {
  { "bande refusee pas morte", 'g.band_state == nil or g.band_state == "refuse"', "g.band_state == nil" },
  { "annule meme en chantier", "if Ln.CANCELLABLE[it.state] then", "if true then" },
  { "plafond retire", "refused > 0 and refused < Ln.MAX_TRIES", "refused > 0" },
  { "redemande malgre un vivant", "if not alive and refused > 0", "if refused > 0" },
}
local caught = 0
for _, m in ipairs(muts) do
  local s2, n = src:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")), 1)
  assert(n == 1, "mutant introuvable : " .. m[1])
  local M = assert(load(s2))()
  local x = run(M)
  if not (x.c1 and x.c2 and x.c3 and x.c4 and x.c5 and x.c6 and x.c7 and x.c8) then caught = caught + 1 else print("mutant survivant : " .. m[1]) end
end
check(caught == #muts, string.format("mutants refuses : %d sur %d", caught, #muts))

print(string.format("[CHAMP-LIEN] BILAN : %d OK, %d ECHEC(S)", okc, fail))
if fail > 0 then os.exit(1) end
