--[[
  tests/entrepreneur_test.lua — règle pure de l'entrepreneur (shared/team/entrepreneur.lua). Usage : lua5.2 tests/entrepreneur_test.lua

  HONNÊTETÉ : la §5 est une SIMULATION LOGIQUE sur un MODÈLE JOUET, pas une mesure en jeu. Modèle explicite :
    - pas d'une minute, 60 minutes ;
    - fer produit par minute = min(foreuses x débit d'une foreuse, fours x débit d'un four) ;
    - une part `reinvest` de la production va au fonds des bandes ; une bande coûte `band_cost` fer (PARAMÈTRE) et ajoute
      `band_drills` foreuses et `band_furn` fours après `build_min` minutes de pose ;
    - AVEC entrepreneur : monopole (rien n'est rendu), ouvrier dédié et craft groupé (pose en build_min) ;
    - SANS entrepreneur (pioche au compte-gouttes partagée) : à chaque minute une part (1 - share) de la réserve repart vers
      d'autres projets, et la pose dure build_min x slow (ouvrier partagé, craft pièce par pièce).
  Les deux séries sont imprimées ; seule la logique est prouvée ici.
]]
package.path = "./?.lua;" .. package.path
local E = require("shared.team.entrepreneur")

local ok, ko = 0, 0
local function check(cond, msg)
  if cond then ok = ok + 1 else ko = ko + 1; print("ECHEC : " .. msg) end
end

-- §1 décision du scan
do
  local a, c = E.decide({ delta = 120, room = true, busy = false, inflight = false })
  check(a == "declenche", "plaques + place + libre : declenche (" .. tostring(a) .. ", " .. tostring(c) .. ")")
  a = E.decide({ delta = 120, room = true, busy = false, inflight = true })
  check(a == "attache", "bande deja en vol : attache")
  a, c = E.decide({ delta = 0, room = true })
  check(a == "refus" and c == "aucune plaque produite", "aucune plaque : refus")
  a, c = E.decide({ delta = 50, room = false })
  check(a == "refus" and c == "aucune place sur un gisement", "aucune place : refus")
  a = E.decide({ delta = 50, room = true, cover = 900 })
  check(a == "refus", "couverture >= 850 permille : plein")
  a = E.decide({ delta = 50, room = true, cover = 849 })
  check(a == "declenche", "couverture 849 permille : place")
  a = E.decide({ delta = 50, room = false, recense = true })
  check(a == "declenche", "gisement recense exploitable : declenche")
  a, c = E.decide({ delta = 50, room = true, busy = true })
  check(a == "refus" and c == "chantier en cours", "un chantier a la fois par equipe")
end

-- §2 monopole et tête de réservation
do
  check(E.monopoly({ entrepreneur = true }), "spec.entrepreneur : monopole")
  check(not E.monopoly({ pile = "capi" }), "projet ordinaire : pas de monopole")
  check(not E.monopoly(nil), "sans spec : pas de monopole")
  local o = E.order({ { id = 3, spec = {} }, { id = 9, spec = { entrepreneur = true } }, { id = 1, spec = {} } })
  check(o[1].id == 9 and o[2].id == 1 and o[3].id == 3, "entrepreneur en tete, puis numeros croissants")
end

-- §3 ouvrier dédié (déterministe, remplacé à sa mort)
do
  local alive = { [4] = true, [7] = true, [2] = true }
  check(E.pick_worker({ 7, 4, 2 }, alive, nil) == 2, "plus petit numero vivant")
  check(E.pick_worker({ 7, 4, 2 }, alive, 7) == 7, "ouvrier courant garde s'il vit")
  alive[7] = nil
  check(E.pick_worker({ 7, 4, 2 }, alive, 7) == 2, "ouvrier mort : un autre est attache")
  check(E.pick_worker({}, {}, nil) == nil, "aucun PNJ : nil")
  check(E.task_ok(12, 12, nil) and not E.task_ok(12, 5, nil), "ouvrier attache : seulement les taches de son projet")
  check(not E.task_ok(nil, 12, 12) and E.task_ok(nil, 5, nil), "autres ouvriers : pas les taches reservees")
end

-- §4 craft groupé : lots entiers, ordre trié
do
  local m = E.kit_missing({ b = 10, a = 4, c = 2 }, { a = 1, c = 5 })
  check(#m == 2 and m[1].name == "a" and m[1].n == 3 and m[2].name == "b" and m[2].n == 10, "manquants du kit en une fois")
end

-- §5 SIMULATION LOGIQUE (modèle jouet) : 60 min, relevés T+15/30/45/60
do
  local par = { minutes = 60, drills0 = 4, furn0 = 6, drill_rate = 30, furn_rate = 18.75, band_drills = 6, band_furn = 10,
    band_cost = 300, reinvest = 0.5, build_min = 4, share = 0.9, slow = 2.5 }
  local function series(with)
    local s = E.simulate(par, with)
    local out, txt = {}, {}
    for _, t in ipairs({ 0, 15, 30, 45, 60 }) do
      local r = s[t + 1]
      out[#out + 1] = r
      txt[#txt + 1] = string.format("T+%d : %d foreuses, %d fours, %.0f fer/min", t, r.drills, r.furn, r.iron_pm)
    end
    print((with and "AVEC entrepreneur" or "SANS entrepreneur") .. " (modele jouet, cout d'une bande " .. par.band_cost .. " fer) :")
    for _, l in ipairs(txt) do print("  " .. l) end
    return out
  end
  local a, b = series(true), series(false)
  for i = 2, 5 do
    check(a[i].drills > a[i - 1].drills, "foreuses strictement croissantes T+" .. (i - 2) * 15 .. " -> T+" .. (i - 1) * 15)
    check(a[i].furn > a[i - 1].furn, "fours strictement croissants T+" .. (i - 2) * 15 .. " -> T+" .. (i - 1) * 15)
    check(a[i].iron_pm > a[i - 1].iron_pm, "fer/min strictement croissant T+" .. (i - 2) * 15 .. " -> T+" .. (i - 1) * 15)
  end
  for i = 2, 5 do check(a[i].iron_pm >= b[i].iron_pm, "avec >= sans a chaque releve (" .. i .. ")") end
  check(a[5].iron_pm > b[5].iron_pm and a[5].drills > b[5].drills, "sans entrepreneur : plus lent a T+60")
  -- le coût d'une bande est bien lu en paramètre : plus cher => plus lent
  local par2 = {}
  for k, v in pairs(par) do par2[k] = v end
  par2.band_cost = 900
  local s2 = E.simulate(par2, true)
  check(s2[61].iron_pm < E.simulate(par, true)[61].iron_pm, "cout de bande en parametre : bande plus chere, croissance plus lente")
end

print(string.format("entrepreneur_test : %d OK, %d ECHEC", ok, ko))
if ko > 0 then os.exit(1) end
