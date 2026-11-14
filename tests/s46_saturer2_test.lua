package.path = "./?.lua;" .. package.path
local St = require("shared.ai3.saturer_tete")
local n_ok = 0
local function ok(c, m) assert(c, m) n_ok = n_ok + 1 end
local orders = { { key = "a", kind = "equiper" }, { key = "b", kind = "couvrir", resource = "r1" },
  { key = "c", kind = "couvrir", resource = "r2" }, { key = "d", kind = "couvrir", resource = "r2" } }
local w = St.wanted({ p1 = { kind = "r2", sat_req = 3 }, p2 = { kind = "r1" }, p3 = { kind = "r3", sat_req = 1, full = true } }, { "p1", "p2", "p3" })
ok(w.r2 and not w.r1 and not w.r3, "seul l'avant-poste sat_req est voulu")
local out, n = St.head(orders, w)
ok(n == 1 and out[1].key == "c", "le premier couvrir de r2 en tete, un seul")
ok(out[2].key == "a" and out[3].key == "b" and out[4].key == "d" and #out == 4, "les autres gardent leur ordre")
local out2, n2 = St.head(orders, {})
ok(n2 == 0 and out2[1].key == "a", "sans drapeau : liste inchangee")
print("s46_saturer2 : " .. n_ok .. " OK")
