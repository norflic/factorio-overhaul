--[[
  MAJA-0916 : le compteur de l'ordre Maj+A (partie réelle 0.9.3 : « 84 bâtiment(s) posé(s) » sans une foreuse électrique dans le cercle).
  Deux fuites du compte de maja-0915 (Co.count_new) :
    1. la case déjà bâtie n'était que la case du CENTRE : un remplacement sur place dont le centre change de tuile (foreuse 2 x 2 -> 3 x 3,
       nouvelle taille d'un bâtiment à niveaux) comptait comme une pose ;
    2. tout bâtiment neuf de l'équipe dans la zone (rayon + 24 : QG, centrale, tapis reconstruits) comptait, même hors du gisement.
  Lancement : lua5.2 tests/maja_0916_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Co = require("shared.ai3.commande")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

local skip = { character = true, ["entity-ghost"] = true }

-- 1. empreinte entière : une foreuse 2 x 2 centrée en (10, 10) couvre les tuiles 9..10 x 9..10
local pre = {}
check(type(Co.mark_box) == "function", "Co.mark_box existe")
if Co.mark_box then
  Co.mark_box(pre, 9, 9, 11, 11)
  check(pre[Co.cell_key(9.5, 9.5)] and pre[Co.cell_key(10.5, 10.5)] and pre[Co.cell_key(9.5, 10.5)], "les 4 tuiles de l'empreinte sont prises")
  check(not pre[Co.cell_key(11.5, 10.5)] and not pre[Co.cell_key(8.5, 9.5)], "rien hors de l'empreinte")
  -- boîte de collision un peu rentrée (-0.4 .. 0.4 d'un tapis en (5.5, 5.5)) : une seule tuile
  local one = {}
  Co.mark_box(one, 5.1, 5.1, 5.9, 5.9)
  local n = 0
  for _ in next, one do n = n + 1 end
  check(n == 1 and one[Co.cell_key(5.5, 5.5)], "tapis : une seule tuile (lu " .. n .. ")")
end
-- remplaçante 3 x 3 centrée en (9.5, 9.5) : son centre (tuile 9,9) était dans l'empreinte de l'ancienne -> pas une pose de l'ordre
local n = Co.count_new({ { un = 2000, x = 9.5, y = 9.5, type = "mining-drill", force = "player", ore = true } }, 900, pre, "player", skip, true)
check(n == 0, "remplacement sur place à centre décalé : non compté (lu " .. n .. ")")

-- 2. ordre de gisement : seules les poses SUR le minerai de l'ordre comptent
local rows = {
  { un = 3001, x = 40.5, y = 40.5, type = "mining-drill", force = "player", ore = true },
  { un = 3002, x = 43.5, y = 40.5, type = "mining-drill", force = "player", ore = true },
  { un = 3003, x = 60.5, y = 60.5, type = "transport-belt", force = "player", ore = false }, -- tapis de la centrale reconstruit
  { un = 3004, x = 61.5, y = 60.5, type = "inserter", force = "player" },                   -- module du QG (minerai non lu)
  { un = 3005, x = 62.5, y = 60.5, type = "entity-ghost", force = "player", ore = false },   -- fantôme hors du gisement
}
local ghost
n, ghost = Co.count_new(rows, 900, {}, "player", skip, true)
check(n == 2, "ordre de gisement : 2 foreuses sur le minerai, le reste non compté (lu " .. n .. ")")
check(ghost == false, "fantôme hors du gisement : pas un plan de l'ordre")
rows[#rows + 1] = { un = 3006, x = 44.5, y = 41.5, type = "entity-ghost", force = "player", ore = true }
n, ghost = Co.count_new(rows, 900, {}, "player", skip, true)
check(ghost == true, "fantôme sur le minerai : plan de l'ordre")
-- sans exigence de minerai (liaison, bastion, amélioration) : règle de maja-0915 inchangée
n = Co.count_new(rows, 900, {}, "player", skip)
check(n == 4, "sans minerai exigé : toutes les poses bâties sur cases libres (lu " .. n .. ")")

print(string.format("maja_0916 : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
