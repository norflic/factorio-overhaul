-- s45 freeze : Mo.memo appelle la fonction une seule fois par clé (y compris pour une valeur nil ou false)
package.path = "./?.lua;" .. package.path
local Mo = require("shared.ai3.moteurs")
local calls = 0
local m = Mo.memo(function(k) calls = calls + 1 if k == "x" then return nil end return k == "a" end)
assert(m("a") == true and m("a") == true)
assert(m("b") == false and m("b") == false)
assert(m("x") == nil and m("x") == nil)
assert(calls == 3, "appels " .. calls)
-- Mo.wants donne le même résultat avec et sans mémo, et le mémo borne les relevés
local fab = {
  r1 = { produits = { "g" }, main = false, patronnable = true, fluides_in = {}, solides = { { name = "p" }, { name = "c" } } },
  r2 = { produits = { "h" }, main = false, patronnable = true, fluides_in = {}, solides = { { name = "g" }, { name = "p" } } },
  r3 = { produits = { "k" }, main = true, patronnable = true, fluides_in = {}, solides = { { name = "h" }, { name = "g" }, { name = "p" } } },
}
local n = 0
local raw = function(it) n = n + 1 return ({ p = 5, c = 3 })[it] or 0 end
local a = Mo.wants(fab, function() return true end, function(i) return raw(i) > 0 end, raw)
local n_raw = n
n = 0
local cnt = Mo.memo(raw)
local b = Mo.wants(fab, function() return true end, Mo.memo(function(i) return cnt(i) > 0 end), cnt)
assert(#a == #b)
for i = 1, #a do assert(a[i].item == b[i].item and a[i].need == b[i].need) end
assert(n < n_raw and n <= 3, "releves " .. n .. " / " .. n_raw)
print("s45_freeze_test OK (" .. n .. " releves au lieu de " .. n_raw .. ")")
