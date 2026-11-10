--[[ Lot CC-BOX (F495, décision du DC du 10/11, 21 h « défense par box ») : les fonderies et les rangées du mall finies ont leur quota de
  tourelles dans la garde de la centrale (shared/team/garde_centrale.lua : G.BOX_WANT, G.split, G.box_entries, G.need, G.plan).
  Partie 0.6.88 du DC (graine 1732508881) : la garde ne connaissait que la centrale ; fonderies et coffres sans tourelle. ]]
package.path = "./?.lua;" .. package.path
local G = require("shared.team.garde_centrale")
local ok, ko = 0, 0
local function check(c, msg) if c then ok = ok + 1 else ko = ko + 1; print("ECHEC : " .. msg) end end
local R = 18
local function row(n, x0, y, dx) local t = {} for i = 0, n - 1 do t[#t + 1] = { x = x0 + i * dx, y = y } end return t end

-- 1. quotas du DC
check(G.BOX_WANT and G.BOX_WANT.fonderie == 4, "fonderie : 4 tourelles")
check(G.BOX_WANT and G.BOX_WANT.mall == 2, "mall : 2 tourelles")
-- 2. une petite fonderie (12 fours en 2 rangées, 12 tuiles) : un seul morceau, quota 4
local small = row(6, 0, 0, 2); for _, p in ipairs(row(6, 0, 4, 2)) do small[#small + 1] = p end
local e = G.box_entries and G.box_entries("fonderie", 7, small, R) or {}
check(#e == 1 and e[1].want == 4 and #e[1].pieces == 12, "petite fonderie : une entrée, quota 4")
check(e[1] and e[1].id == "fonderie:7:1" and e[1].boilers == 0, "id de l'entrée, sans chaudière")
-- 3. une longue fonderie (24 fours sur 70 tuiles) : coupée en morceaux faisables, quota total 4 jamais dépassé
local long = row(24, 0, 0, 3)
local el = G.box_entries and G.box_entries("fonderie", 8, long, R) or {}
local tot, allfeas, n = 0, true, 0
for _, x in ipairs(el) do tot = tot + x.want; n = n + #x.pieces; if not G.feasible(x.pieces, R) then allfeas = false end end
check(#el >= 2, "longue fonderie : plusieurs morceaux (" .. #el .. ")")
check(tot == 4, "longue fonderie : quota total 4 (" .. tot .. ")")
check(allfeas, "chaque morceau couvert d'un seul point")
check(n <= 24 and n >= 1, "pièces conservées")
-- 4. mall : quota 2 ; genre sans quota : rien
local em = G.box_entries and G.box_entries("mall", 1, row(5, 0, 0, 3), R) or {}
check(#em == 1 and em[1].want == 2, "mall : une entrée, quota 2")
check(G.box_entries and #G.box_entries("energie", 1, small, R) == 0, "énergie : pas de quota de box (garde des centrales inchangée)")
check(G.box_entries and #G.box_entries("fonderie", 1, {}, R) == 0, "box sans pièce : rien")
-- 5. G.need lit le quota de la box, pas les chaudières
local nd = G.need(small, 0, {}, R, 1, 4)
check(nd and nd.wanted == 4 and nd.missing == 4, "need : quota 4 sans chaudière")
local np = G.need(small, 3, {}, R, 1)
check(np and np.wanted == G.wanted(3), "need : centrale inchangée")
-- 6. G.plan : une fonderie sans tourelle est choisie ; le plafond de l'équipe ne l'efface pas quand les centrales l'ont rempli
local plant = { id = 1, pieces = row(4, 100, 100, 2), boilers = 5 }
local turrets = {}
for _, s in ipairs(select(1, G.sites(plant.pieces, R, 6))) do turrets[#turrets + 1] = { x = s.x, y = s.y, rounds = 50 } end
local pl2 = { id = 2, pieces = row(4, 300, 100, 2), boilers = 5 }
for _, s in ipairs(select(1, G.sites(pl2.pieces, R, 6))) do turrets[#turrets + 1] = { x = s.x, y = s.y, rounds = 50 } end
local plants = { plant, pl2 }
for _, x in ipairs(e) do plants[#plants + 1] = x end
local pp = G.plan(plants, turrets, R, 1, 12)
check(pp and pp.pick and pp.pick.id == "fonderie:7:1", "plan : la fonderie non gardée est choisie (" .. tostring(pp and pp.pick and pp.pick.id) .. ")")
check(pp and pp.pick and pp.pick.missing == 4, "plan : 4 tourelles à poser")
-- 7. la fonderie gardée à son quota : plus rien à poser (pas de spam)
local t2 = {}
for _, t in ipairs(turrets) do t2[#t2 + 1] = t end
for _, s in ipairs(select(1, G.sites(small, R, 4))) do t2[#t2 + 1] = { x = s.x, y = s.y, rounds = 50 } end
local pq = G.plan(plants, t2, R, 1, 12)
check(pq and pq.pick == nil, "plan : fonderie à son quota, rien de plus")
-- 8. centrales seules : plafond d'avant inchangé (12)
local p0 = G.plan({ plant, pl2 }, {}, R, 1, 12)
check(p0 and p0.left == 12, "centrales seules : plafond 12 inchangé")
print(string.format("[GARDE-BOX] BILAN : %d OK, %d ECHEC(S)", ok, ko))
if ko > 0 then os.exit(1) end
