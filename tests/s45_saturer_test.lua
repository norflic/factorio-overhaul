package.path = "./?.lua;" .. package.path
local Co = require("shared.ai3.commande")
local function ok(c, m) if not c then error(m, 2) end end
local st = Co.new_state()
local id = Co.add(st, { kind = "gisement", x = 0, y = 0, r = 20, resource = "r", outpost = "k", after_oid = 3 })
local ops = { { id = 2, kind = "k", x = 5, y = 5 }, { id = 3, kind = "z", x = 1, y = 1 }, { id = 1, kind = "k", x = 500, y = 0 } }
local sat = Co.saturations(st, ops)
ok(#sat == 1 and sat[1].order == id and sat[1].oid == 2, "seul l'avant-poste deja la, meme type, dans la zone")
ok(#Co.resolve(st, ops) == 0, "avant-poste deja la non couvert : ordre en attente")
ops[1].covered = Co.truly_full("couverture")
ok(#Co.resolve(st, ops) == 1, "couverture complete : ordre rempli")
ok(Co.liftable({ full = true, full_why = "adopte" }), "plein d'adoption leve")
ok(Co.liftable({ full = true, hold_until = 9 }), "attente leve")
ok(not Co.liftable({ full = true, full_why = "couverture" }), "couvert : garde")
ok(not Co.liftable({ full = true, migr = "en cours" }), "migration en cours : garde")
ok(not Co.liftable({ full = true, full_why = "electrique" }), "combustion : garde")
ok(#Co.saturations(st, { { id = 4, kind = "k", x = 0, y = 0 } }) == 0, "avant-poste neuf : pas de saturation")
print("s45_saturer OK")
