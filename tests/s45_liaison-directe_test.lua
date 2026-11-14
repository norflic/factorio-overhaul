package.path = "./?.lua;" .. package.path
local Li = require("shared.team.liaison")
local blocked = { ["5:4"] = "occ", ["6:5"] = "guard", ["7:5"] = "fronts" }
local function why(x, y) return blocked[x .. ":" .. y] end
local r = Li.block_report(5, 5, why)
assert(r == "N:occ/libre,E:guard/fronts,S:libre/libre,O:libre/libre", r)
assert(Li.block_report(0, 0, function() return nil end) == "N:libre/libre,E:libre/libre,S:libre/libre,O:libre/libre")
print("s45_liaison-directe_test : 2 OK")
