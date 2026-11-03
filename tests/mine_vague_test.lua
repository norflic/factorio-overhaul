--[[
  Lot FONDERIE-M (3/11) : le minage à la main prudent et de fond évite les sites où une vague est attendue ou insurmontable
  (shared/team/mine_vague.lua ; branché par script/team/worker.lua, script/ai3/prevision.lua, script/ai3/soldats.lua).
  Lancement : lua5.2 tests/mine_vague_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Mv = require("shared.team.mine_vague")

local okc, fail = 0, 0
local function check(cond, msg) if cond then okc = okc + 1 else fail = fail + 1; print("ECHEC : " .. msg) end end
local function read(p) local h = assert(io.open(p, "r")); local s = h:read("*a"); h:close(); return s end

-- cas mesuré (verif-guide 1618033988) : QG en (0, 0), avant-poste de fer ap1 en (49, -50) jugé insurmontable, ap4 en (108, -29) sans vague
local SITES = { { key = "qg", kind = "qg", x = 0, y = 0 }, { key = "ap1", kind = "ap", x = 49, y = -50 }, { key = "ap4", kind = "ap", x = 108, y = -29 },
  { key = "ch3", kind = "ch", x = -120, y = -34 } }
local STATES = { qg = { prep = true, insurm = true }, ap1 = { prep = false, insurm = true }, ap4 = { prep = false, insurm = false }, ch3 = { prep = true } }

local function run(M)
  local r = {}
  local w = M.from_states(SITES, STATES)
  r.n = #w
  r.has_ap1 = false; r.has_ch3 = false; r.has_qg = false; r.has_ap4 = false
  for _, s in ipairs(w) do
    if s.x == 49 and s.y == -50 then r.has_ap1 = true end
    if s.x == -120 then r.has_ch3 = true end
    if s.x == 0 and s.y == 0 then r.has_qg = true end
    if s.x == 108 then r.has_ap4 = true end
  end
  r.death1 = M.blocked(40, -49, w)        -- PNJ 1 tué en minant à 36,0 min
  r.death2 = M.blocked(40, -50, w)        -- PNJ 17 (fond)
  r.edge_in = M.blocked(49 + 40, -50, w)  -- à 40 tuiles pile : écarté
  r.edge_out = M.blocked(49 + 40.5, -50, w)
  r.far = M.blocked(108, -29, w)          -- ap4 sans vague
  r.qg = M.blocked(5, 5, w)               -- près du QG : toujours permis
  r.none = M.blocked(40, -49, {})
  return r
end

local r = run(Mv)
check(r.n == 2 and r.has_ap1 and r.has_ch3 and not r.has_qg and not r.has_ap4, "sites menaces : ap1 (insurmontable) et ch3 (preparer) ; ni le QG ni ap4 (" .. r.n .. ")")
check(r.death1 and r.death2, "les deux tuiles ou des PNJ sont morts en minant (40, -49) et (40, -50) sont ecartees")
check(r.edge_in and not r.edge_out, "limite : 40 tuiles ecartees, 40,5 permises")
check(not r.far and not r.qg and not r.none, "permis : site sans vague, abords du QG, aucune vague")
check(Mv.R == 40, "rayon 40 tuiles")

-- branchement (lecture des sources) : crochet posé, sites lus à la prévision, minage prudent ET de fond concernés
local W, P, S = read("script/team/worker.lua"), read("script/ai3/prevision.lua"), read("script/ai3/soldats.lua")
check(W:find("local waves = (task.fond or task.prudent) and Worker.wave_sites and Worker.wave_sites(f) or nil", 1, true) ~= nil,
  "worker : minage prudent ou de fond lit les sites menaces")
check(W:find("if busy == 0 and waves and #waves > 0 and Mv.blocked(p.x, p.y, waves) then busy = 1", 1, true) ~= nil, "worker : tuile menacee ecartee")
check(P:find("function Prev.wave_sites(f)", 1, true) ~= nil and P:find("Mv.from_states(sites_of(f), st.pc.sites)", 1, true) ~= nil,
  "prevision : Prev.wave_sites filtre ses sites par la regle")
check(S:find("Worker.wave_sites = Prev.wave_sites", 1, true) ~= nil, "soldats : crochet pose")
check(P:find("^local function sites_of") == nil and P:find("\nlocal function sites_of", 1, true) < P:find("\nfunction Prev.wave_sites", 1, true),
  "prevision : Prev.wave_sites definie APRES sites_of (locale visible)")

-- mutants
local src = read("shared/team/mine_vague.lua")
local muts = {
  { "QG non exclu", 's.kind ~= "qg" and ps', "ps" },
  { "preparer ignore", "(ps.prep == true or ps.insurm == true)", "ps.insurm == true" },
  { "rayon nul", "Mv.R = 40", "Mv.R = 0" },
  { "limite exclue", "<= r2 then return true", "< r2 then return true" },
}
local caught = 0
for _, m in ipairs(muts) do
  local s, n = src:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")), 1)
  assert(n == 1, "mutant introuvable : " .. m[1])
  local M = assert(load(s))()
  local x = run(M)
  local good = x.n == 2 and x.has_ap1 and x.has_ch3 and not x.has_qg and x.death1 and x.death2 and x.edge_in and not x.edge_out and not x.far and not x.qg
  if not good or M.R ~= 40 then caught = caught + 1 else print("mutant survivant : " .. m[1]) end
end
check(caught == #muts, string.format("mutants refuses : %d sur %d", caught, #muts))

print(string.format("[MINE-VAGUE] BILAN : %d OK, %d ECHEC(S)", okc, fail))
if fail > 0 then os.exit(1) end
