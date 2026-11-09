--[[
  Lot PURETE-TAPIS (retour du DC du 8/11 vers 18 h 30, 0.6.71) : garde-fou de pureté des tapis posés par les PNJ (shared/team/purete.lua),
  hors jeu, Lua pur : lua5.2 tests/purete_test.lua   (depuis la racine du mod)

    §1  objet étranger : inconnu compte comme étranger, seul le même objet déclaré ou vu passe ;
    §2  tracé libre accepté ; la preuve ne se plaint de rien quand le monde est vide ;
    §3  (a) un tracé qui pointe vers un tapis d'un autre objet est refusé, bout à bout et par le côté ; cible déclarée admise ;
    §4  (b) un tapis étranger qui pointe vers une tuile du tracé est refusé (tapis, répartiteur, sortie de souterrain), pas une entrée de
        souterrain, pas un tapis qui regarde ailleurs ;
    §5  (c) croisement d'une ligne étrangère : refusé sans souterrain, admis par une paire, refusé sous une pièce souterraine de même axe ;
    §6  cas tirés de la partie du DC (0.6.71, journal du 8/11 18 h 30) : positions des tampons et des quais de scarlet ;
    §7  queues d'un gabarit réel (rangée d'engrenages, circuits) : la tuile devant le tapis d'entrée ;
    §8  tuiles interdites à l'A* (Pu.forbidden), déterminisme, aucun nom d'objet, aucun pairs dans une décision ;
    §9  journal : ligne [FO-PURETE] ;
    §10 MUTANTS : chaque règle de shared/team/purete.lua cassée (une substitution du source) est vue par la batterie.
]]

package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/purete.lua")
local function load_pu(src)
  local fn, err = load(src, "=purete", "t")
  assert(fn, err)
  return fn()
end

local total_ok, total_fail = 0, 0

--- Une tuile du monde.
local function rec(x, y, dir, kind, item, seen) return { x = x, y = y, dir = dir, kind = kind or "belt", item = item, seen = seen } end

--- Monde en table, depuis une liste d'enregistrements.
local function world_of(Pm, list)
  local w = {}
  for _, r in ipairs(list) do w[Pm.tkey(r.x, r.y)] = r end
  return w
end

--- Tracé droit vers l'est de (x0, y) à (x1, y).
local function east(x0, x1, y)
  local t = {}
  for x = x0, x1 do t[#t + 1] = { x = x, y = y, dir = 2 } end
  return t
end

local function causes(bad)
  local out = {}
  for _, b in ipairs(bad) do out[#out + 1] = b.cause end
  table.sort(out)
  return table.concat(out, ",")
end

local function battery(Pm, verbose, M, Plan)
  local bad_n, n = 0, 0
  local function chk(cond, label)
    n = n + 1
    if not cond then
      bad_n = bad_n + 1
      if verbose then print("ECHEC : " .. label) end
    end
  end
  local function W(list) return world_of(Pm, list) end

  -------------------------------------------------------------------------------------------------
  -- §1 objet étranger
  -------------------------------------------------------------------------------------------------
  chk(Pm.foreign(rec(0, 0, 2, "belt", nil), "iron-plate") == true, "1.1 un tapis inconnu (ni déclaré ni vu) est étranger")
  chk(Pm.foreign(rec(0, 0, 2, "belt", "iron-plate"), "iron-plate") == false, "1.2 même objet déclaré : pas étranger")
  chk(Pm.foreign(rec(0, 0, 2, "belt", "copper-plate"), "iron-plate") == true, "1.3 autre objet déclaré : étranger")
  chk(Pm.foreign(rec(0, 0, 2, "belt", nil, { "iron-plate" }), "iron-plate") == false, "1.4 même objet vu : pas étranger")
  chk(Pm.foreign(rec(0, 0, 2, "belt", "iron-plate", { "iron-plate", "stone" }), "iron-plate") == true, "1.5 un autre objet vu rend le tapis étranger")
  chk(Pm.foreign(rec(0, 0, 2, "belt", "iron-plate"), nil) == true, "1.6 notre objet inconnu : tout tapis est étranger")
  chk(Pm.foreign(nil, "iron-plate") == false, "1.7 rien n'est pas étranger")
  chk(Pm.label(rec(0, 0, 2, "belt", "b", { "a", "b" })) == "a+b" and Pm.label(rec(0, 0, 2, "belt")) == "?", "1.8 étiquette triée, « ? » si inconnu")

  -- ligne à deux objets (un par voie) : la pureté se juge par TAPIS entier
  chk(Pm.foreign(rec(0, 0, 2, "belt", { "a", "b" }), { "a", "b" }) == false, "1.9 tapis déclaré a|b contre une ligne a|b : pas étranger")
  chk(Pm.foreign(rec(0, 0, 2, "belt", { "a", "b" }), "a") == true, "1.10 tapis a|b contre une ligne qui ne porte que a : étranger")
  chk(Pm.foreign(rec(0, 0, 2, "belt", "a"), { "a", "b" }) == false, "1.11 tapis a contre une ligne a|b : admis (ses objets sont parmi les nôtres)")
  chk(Pm.foreign(rec(0, 0, 2, "belt", "c"), { "a", "b" }) == true and Pm.item_label({ "b", "a" }) == "a+b", "1.12 autre objet : étranger ; étiquette triée")

  -------------------------------------------------------------------------------------------------
  -- §2 tracé libre
  -------------------------------------------------------------------------------------------------
  do
    local ok, bad = Pm.check(east(0, 9, 0), "iron-plate", {}, {})
    chk(ok and #bad == 0, "2.1 monde vide : accepté")
    local ok2 = Pm.check(east(0, 9, 0), "iron-plate", W({ rec(3, 5, 2, "belt", "copper-plate") }), {})
    chk(ok2, "2.2 un tapis étranger loin du tracé ne gêne pas")
    local ok3 = Pm.check(east(0, 9, 0), "iron-plate", W({ rec(3, 1, 2, "belt", "copper-plate") }), {})
    chk(ok3, "2.3 une ligne étrangère PARALLÈLE, à côté, ne gêne pas")
    local ok4, bad4 = Pm.check({ { x = 0, y = 0, dir = 2 }, { x = 5, y = 0, dir = 2 } }, "iron-plate", {}, {})
    chk(not ok4 and causes(bad4) == "chaine_rompue", "2.4 un trou dans la chaîne est dit : " .. causes(bad4))
  end

  -------------------------------------------------------------------------------------------------
  -- §3 (a) le tracé pointe vers un tapis étranger
  -------------------------------------------------------------------------------------------------
  do
    local line = east(0, 9, 0)
    -- bout à bout : la tuile (10, 0) porte un tapis d'un autre objet
    local ok, bad = Pm.check(line, "iron-plate", W({ rec(10, 0, 2, "belt", "copper-plate") }), {})
    chk(not ok and causes(bad) == "pointe_vers_etranger", "3.1 bout à bout contre un autre objet : refusé (" .. causes(bad) .. ")")
    chk(bad[1] and bad[1].x == 9 and bad[1].y == 0 and bad[1].wx == 10, "3.2 le refus cite la tuile du tracé et celle du monde")
    -- par le côté : le tapis étranger est tourné en travers, la dernière tuile verse dessus par son flanc
    local ok2, bad2 = Pm.check(line, "iron-plate", W({ rec(10, 0, 4, "belt", "copper-plate") }), {})
    chk(not ok2 and causes(bad2) == "pointe_vers_etranger", "3.3 par le côté : refusé")
    -- inconnu : refusé
    local ok3 = Pm.check(line, "iron-plate", W({ rec(10, 0, 2, "belt", nil) }), {})
    chk(not ok3, "3.4 tapis inconnu devant : refusé")
    -- même objet déclaré : admis
    local ok4 = Pm.check(line, "iron-plate", W({ rec(10, 0, 2, "belt", "iron-plate") }), {})
    chk(ok4, "3.5 même objet déclaré devant : admis")
    -- cible déclarée (bras du quai, tampon) : admise même étrangère
    local ok5 = Pm.check(line, "iron-plate", W({ rec(10, 0, 2, "belt", "copper-plate") }), { targets = { [Pm.tkey(10, 0)] = true } })
    chk(ok5, "3.6 la cible déclarée est admise")
    -- une tuile INTERMÉDIAIRE ne verse que sur la suivante : un tapis étranger à côté ne compte pas
    local ok6 = Pm.check(line, "iron-plate", W({ rec(4, 1, 2, "belt", "copper-plate"), rec(4, -1, 0, "belt", "copper-plate") }), {})
    chk(ok6, "3.7 un tapis étranger tangent au flanc du tracé ne reçoit rien")
    -- une entrée de souterrain étrangère devant : refusé aussi
    local ok7 = Pm.check(line, "iron-plate", W({ rec(10, 0, 2, "ug_in", "copper-plate") }), {})
    chk(not ok7, "3.8 entrée de souterrain étrangère devant : refusé")
  end

  -------------------------------------------------------------------------------------------------
  -- §4 (b) un tapis étranger pointe vers le tracé
  -------------------------------------------------------------------------------------------------
  do
    local line = east(0, 9, 0)
    local ok, bad = Pm.check(line, "iron-plate", W({ rec(4, 1, 0, "belt", "copper-plate") }), {})
    chk(not ok and causes(bad) == "etranger_pointe_vers", "4.1 un tapis étranger au sud tourné vers le nord verse sur le tracé : refusé (" .. causes(bad) .. ")")
    chk(bad[1] and bad[1].x == 4 and bad[1].y == 0 and bad[1].wy == 1, "4.2 le refus cite la tuile visée")
    local ok2 = Pm.check(line, "iron-plate", W({ rec(4, 1, 4, "belt", "copper-plate") }), {})
    chk(ok2, "4.3 le même tapis tourné AILLEURS (vers le sud) ne verse pas sur le tracé")
    local ok3, bad3 = Pm.check(line, "iron-plate", W({ rec(-1, 0, 2, "belt", "copper-plate") }), {})
    chk(not ok3 and causes(bad3) == "etranger_pointe_vers", "4.4 un tapis étranger derrière la première tuile, tourné vers elle : refusé")
    chk(Pm.check(line, "iron-plate", W({ rec(-1, 0, 2, "belt", "copper-plate") }), { first = false }), "4.5 option first = false : la première tuile n'est pas lue")
    local ok6 = Pm.check(line, "iron-plate", W({ rec(4, 1, 0, "belt", "iron-plate") }), {})
    chk(ok6, "4.6 un tapis du MÊME objet déclaré qui verse sur le tracé : admis")
    local ok7 = Pm.check(line, "iron-plate", W({ rec(4, 1, 0, "splitter", "copper-plate") }), {})
    chk(not ok7, "4.7 une tuile de répartiteur étrangère qui verse sur le tracé : refusé")
    local ok8 = Pm.check(line, "iron-plate", W({ rec(4, 1, 0, "ug_in", "copper-plate") }), {})
    chk(ok8, "4.8 une entrée de souterrain ne verse rien devant elle : admise")
    local ok9 = Pm.check(line, "iron-plate", W({ rec(4, 1, 0, "ug_out", "copper-plate") }), {})
    chk(not ok9, "4.9 une sortie de souterrain étrangère qui verse sur le tracé : refusée")
    local ok10 = Pm.check(line, "iron-plate", W({ rec(4, 1, 0, "belt", nil) }), {})
    chk(not ok10, "4.10 un tapis inconnu qui verse sur le tracé : refusé")
    local ok11 = Pm.check(line, "iron-plate", W({ rec(4, 1, 0, "belt", "copper-plate") }), { own = { [Pm.tkey(4, 1)] = true } })
    chk(ok11, "4.11 les tuiles de notre propre projet ne sont jamais lues comme tapis du monde")
    local ok12 = Pm.check(line, "iron-plate", function(x, y) if x == 4 and y == 1 then return rec(4, 1, 0, "belt", "copper-plate") end end, {})
    chk(not ok12, "4.12 le monde peut être une fonction")
  end

  -------------------------------------------------------------------------------------------------
  -- §5 (c) croisement
  -------------------------------------------------------------------------------------------------
  do
    local ok, bad = Pm.check(east(0, 9, 0), "iron-plate", W({ rec(5, 0, 0, "belt", "copper-plate") }), {})
    chk(not ok and causes(bad):find("croisement_sans_souterrain"), "5.1 une tuile posée sur une ligne étrangère : refusée (" .. causes(bad) .. ")")
    local ok2, bad2 = Pm.check(east(0, 9, 0), "iron-plate", W({ rec(5, 0, 0, "belt", "iron-plate") }), {})
    chk(not ok2 and causes(bad2):find("occupe"), "5.2 sur le même objet : « occupe » (" .. causes(bad2) .. ")")
    -- paire souterraine de (3,0) à (7,0) sous la ligne étrangère en (5,0)
    local pair = {
      { x = 0, y = 0, dir = 2 }, { x = 1, y = 0, dir = 2 }, { x = 2, y = 0, dir = 2 },
      { x = 3, y = 0, dir = 2, ug = "input" }, { x = 7, y = 0, dir = 2, ug = "output" },
      { x = 8, y = 0, dir = 2 }, { x = 9, y = 0, dir = 2 },
    }
    local ok3 = Pm.check(pair, "iron-plate", W({ rec(5, 0, 0, "belt", "copper-plate"), rec(5, 1, 0, "belt", "copper-plate"), rec(5, -1, 0, "belt", "copper-plate") }), {})
    chk(ok3, "5.3 une ligne étrangère croisée par une paire souterraine : admise")
    local ok4, bad4 = Pm.check(pair, "iron-plate", W({ rec(5, 0, 2, "ug_in", "copper-plate") }), {})
    chk(not ok4 and causes(bad4):find("souterrain_meme_axe"), "5.4 sous une pièce souterraine étrangère de même axe : refusée (" .. causes(bad4) .. ")")
    local ok5 = Pm.check(pair, "iron-plate", W({ rec(5, 0, 0, "ug_in", "copper-plate") }), {})
    chk(ok5, "5.5 sous une pièce souterraine d'axe perpendiculaire : admise")
    local ok6, bad6 = Pm.check(pair, "iron-plate", W({ rec(4, 0, 2, "ug", "copper-plate") }), {})
    chk(not ok6 and causes(bad6):find("souterrain_meme_axe"), "5.6 souterrain de sens inconnu de même axe : refusé")
    -- tuile d'entrée posée avec un tapis qui lui verse dessus par derrière
    local ok7 = Pm.check(pair, "iron-plate", W({ rec(3, 1, 0, "belt", "copper-plate") }), {})
    chk(not ok7, "5.7 un tapis étranger qui verse sur l'entrée du souterrain : refusé")
  end

  -------------------------------------------------------------------------------------------------
  -- §6 cas tirés de la partie du DC (journal du 8/11, 0.6.71, équipe scarlet)
  -------------------------------------------------------------------------------------------------
  do
    -- liaison projet 65 : electronic-circuit de la sortie (420, -333) au quai (400, -294) ; le rapatriement transport-belt (projets 40, 41,
    -- 52) finit au tampon (403, -339) : sa dernière tuile (404, -339) regarde l'ouest. Positions réelles, géométrie synthétique.
    local transport_tail = rec(404, -339, 6, "belt", "transport-belt")
    -- un tracé de circuits qui longe le tampon par le nord et passe à (403, -339) : la dernière tuile du rapatriement verse sur lui
    local circuits = { { x = 403, y = -340, dir = 4 }, { x = 403, y = -339, dir = 4 }, { x = 403, y = -338, dir = 4 } }
    local ok, bad = Pm.check(circuits, "electronic-circuit", W({ transport_tail }), {})
    chk(not ok and causes(bad):find("etranger_pointe_vers"), "6.1 circuits contre la queue du rapatriement de transport-belt : refusé (" .. causes(bad) .. ")")
    -- liaison projet 77 : iron-gear-wheel de (447, -295) au quai (401, -286) sur la ligne y = -286 ; le tampon de plaques est en (405, -286)
    local plates = rec(406, -286, 6, "belt", "iron-plate")
    local gears = {}
    for x = 410, 402, -1 do gears[#gears + 1] = { x = x, y = -286, dir = 6 } end
    local ok2, bad2 = Pm.check(gears, "iron-gear-wheel", W({ plates }), {})
    chk(not ok2, "6.2 engrenages sur la ligne des plaques : refusé (" .. causes(bad2) .. ")")
    -- la même ligne, deux tuiles plus bas : rien ne touche
    local gears2 = {}
    for x = 410, 402, -1 do gears2[#gears2 + 1] = { x = x, y = -284, dir = 6 } end
    chk(Pm.check(gears2, "iron-gear-wheel", W({ plates }), {}), "6.3 deux tuiles plus bas : admis")
    -- rangée de circuits, queue du tapis d'entrée (plaques) qui sort de l'emprise : le tracé des circuits ne doit pas se poser devant
    local row_tail = rec(18, 0, 2, "belt", nil, { "iron-plate" })
    local route = { { x = 19, y = 0, dir = 4 }, { x = 19, y = 1, dir = 4 } }
    local ok4, bad4 = Pm.check(route, "electronic-circuit", W({ row_tail }), {})
    chk(not ok4 and causes(bad4):find("etranger_pointe_vers"), "6.4 devant la queue d'une rangée (plaques vues) : refusé")
    chk(Pm.check(route, "iron-plate", W({ row_tail }), {}), "6.5 ... mais pas pour une ligne de plaques, objet vu identique")
  end

  -------------------------------------------------------------------------------------------------
  -- §7 queues d'un gabarit réel
  -------------------------------------------------------------------------------------------------
  if M and Plan then
    -- (la règle de la batterie, pas celle de plan.lua : les mutants doivent être vus ; plan.lua est comparé juste après)
    local function tails_of(inst, room)
      local belts, occ, skip = {}, {}, {}
      for _, e in ipairs(inst.entities) do
        local ent = { name = e.name, x = e.position.x, y = e.position.y, dir = e.direction or 0 }
        for _, t in ipairs(Plan.tiles_of(ent)) do occ[Pm.tkey(t[1], t[2])] = true end
        local sp = M.spec(e.name)
        if sp and sp.kind == "belt" then belts[#belts + 1] = { x = math.floor(ent.x), y = math.floor(ent.y), dir = ent.dir } end
      end
      for _, t in ipairs(room or {}) do skip[Pm.tkey(t[1], t[2])] = true end
      return Pm.tails(belts, occ, skip)
    end
    local g = assert(M.GEN.gears(3, "assembling-machine-2"))
    local inst0 = M.instantiate(g, 0, 0, 0)
    local room0 = Plan.port_room(inst0)
    local tails = tails_of(inst0, room0)
    chk(#Plan.template_tails(inst0, room0) == #tails, "7.0 plan.lua et la batterie trouvent les mêmes queues")
    local seen = {}
    for _, t in ipairs(tails) do seen[#seen + 1] = t.x .. ":" .. t.y end
    chk(table.concat(seen, ",") == "11:0", "7.1 rangée d'engrenages : une seule queue libre, la tuile (11, 0) devant le tapis d'entrée (" .. table.concat(seen, ",") .. ")")
    local bad = Pm.tail_refusals(tails, 5, 7, nil, W({ rec(16, 7, 2, "belt", "copper-plate") }), nil)
    chk(#bad == 1 and bad[1].cause == "pointe_vers_etranger" and bad[1].wx == 16 and bad[1].wy == 7, "7.2 un gabarit posé à (5, 7) dont la queue vise un tapis étranger : refusé")
    chk(#Pm.tail_refusals(tails, 5, 7, nil, W({ rec(16, 8, 2, "belt", "copper-plate") }), nil) == 0, "7.3 le tapis une tuile à côté : admis")
    chk(#Pm.tail_refusals(tails, 5, 7, "x", W({ rec(16, 7, 2, "belt", "x") }), nil) == 0, "7.4 même objet déclaré devant la queue : admis")
    local g2 = assert(M.GEN.circuits("assembling-machine-2", 2))
    local inst2 = M.instantiate(g2, 0, 0, 0)
    local t2 = tails_of(inst2, Plan.port_room(inst2))
    chk(#t2 >= 1 and t2[1].x == 19 and t2[1].y == 0, "7.5 circuits : queue en (19, 0)")
  end

  -------------------------------------------------------------------------------------------------
  -- §8 tuiles interdites, déterminisme
  -------------------------------------------------------------------------------------------------
  do
    local recs = { rec(4, 1, 0, "belt", "copper-plate"), rec(8, 2, 6, "splitter", nil), rec(9, 9, 2, "ug_in", "x"), rec(3, 3, 2, "belt", "iron-plate") }
    local f = Pm.forbidden(recs, "iron-plate", nil)
    chk(f[Pm.tkey(4, 0)] == true and f[Pm.tkey(7, 2)] == true, "8.1 les tuiles devant les tapis étrangers sont interdites")
    chk(f[Pm.tkey(10, 9)] ~= true, "8.2 une entrée de souterrain ne verse pas : sa tuile n'est pas interdite")
    chk(f[Pm.tkey(4, 3)] ~= true, "8.3 le tapis du même objet n'interdit rien")
    local f2 = Pm.forbidden(recs, "iron-plate", { [Pm.tkey(4, 1)] = true })
    chk(f2[Pm.tkey(4, 0)] ~= true, "8.4 les tuiles de notre projet sont ignorées")
    local a = Pm.check(east(0, 9, 0), "iron-plate", W({ rec(4, 1, 0, "belt", "a"), rec(5, 1, 0, "belt", "b"), rec(10, 0, 2, "belt", "c") }), {})
    local _, b1 = Pm.check(east(0, 9, 0), "iron-plate", W({ rec(4, 1, 0, "belt", "a"), rec(5, 1, 0, "belt", "b"), rec(10, 0, 2, "belt", "c") }), {})
    local _, b2 = Pm.check(east(0, 9, 0), "iron-plate", W({ rec(10, 0, 2, "belt", "c"), rec(5, 1, 0, "belt", "b"), rec(4, 1, 0, "belt", "a") }), {})
    chk(a == false and #b1 == 3 and causes(b1) == causes(b2), "8.5 trois refus, mêmes causes quel que soit l'ordre de construction du monde")
  end

  -------------------------------------------------------------------------------------------------
  -- §9 journal
  -------------------------------------------------------------------------------------------------
  do
    local _, bad = Pm.check(east(0, 9, 0), "iron-plate", W({ rec(10, 0, 2, "belt", "copper-plate") }), {})
    local line = Pm.line("liaison", bad[1])
    chk(line == "[FO-PURETE] liaison : tracé refusé (pointe_vers_etranger) objet iron-plate contre copper-plate en (10, 0)", "9.1 ligne du journal : " .. line)
    local line2 = Pm.line("rapatriement", bad[1], "scarlet")
    chk(line2:find("^%[FO%-PURETE%] scarlet rapatriement : tracé refusé"), "9.2 ligne avec l'équipe")
  end

  return bad_n, n
end

local Pu = load_pu(SRC)
local M = require("shared.team.modules")
local Plan = require("shared.team.plan")

local bad, n = battery(Pu, true, M, Plan)
total_ok, total_fail = total_ok + (n - bad), total_fail + bad

-------------------------------------------------------------------------------------------------
-- §8 suite : aucun nom d'objet, aucun pairs dans une décision (lecture du source)
-------------------------------------------------------------------------------------------------
do
  local function chk(cond, label)
    if cond then total_ok = total_ok + 1 else total_fail = total_fail + 1 print("ECHEC : " .. label) end
  end
  local code = SRC:gsub("%-%-%[%[.-%]%]", "", 1):gsub("%-%-[^\n]*", "")
  chk(not code:find("iron%-") and not code:find("copper") and not code:find("transport%-belt") and not code:find("underground%-belt"), "8.6 aucun nom d'objet dans le code de la règle")
  chk(not code:find("pairs%(") or not code:gsub("ipairs%(", ""):find("pairs%("), "8.7 aucun pairs() dans la règle")
  chk(not code:find("math%.sin") and not code:find("math%.cos") and not code:find("os%.clock") and not code:find("os%.time"), "8.8 ni trigonométrie ni temps mesuré")
end

-------------------------------------------------------------------------------------------------
-- §10 mutants
-------------------------------------------------------------------------------------------------
local MUTANTS = {
  { "inconnu admis", [[  if #items == 0 then return true end]], [[  if #items == 0 then return false end]] },
  { "objet identique ignoré", [[    if not mine[it] then return true end]], [[    if mine[it] then return true end]] },
  { "(a) bout à bout oublié", [[bad[#bad + 1] = refusal("pointe_vers_etranger", t, w, item)]], [[local _ = 0]] },
  { "(a) cible déclarée ignorée", [[elseif not targets[tkey(fx, fy)] then]], [[else]] },
  { "(b) étranger qui verse oublié", [[bad[#bad + 1] = refusal("etranger_pointe_vers", t, w, item)]], [[local _ = 0]] },
  { "(b) entrée de souterrain versante", [[return rec ~= nil and rec.kind ~= "ug_in"]], [[return rec ~= nil]] },
  { "(b) sens du tapis ignoré", [[if w and w.dir == d and Pu.outputs(w) and Pu.foreign(w, item) then]], [[if w and Pu.outputs(w) and Pu.foreign(w, item) then]] },
  { "(c) croisement admis", [[bad[#bad + 1] = refusal(Pu.foreign(here, item) and "croisement_sans_souterrain" or "occupe", t, here, item)]], [[local _ = 0]] },
  { "(c) même objet pris pour un croisement", [[Pu.foreign(here, item) and "croisement_sans_souterrain" or "occupe"]], [[true and "croisement_sans_souterrain" or "occupe"]] },
  { "(d) pièce souterraine sous la paire ignorée", [[if is_ug(w) and axis_of(w.dir or 0) == axis_of(a.dir) then]], [[if false then]] },
  { "(d) axe perpendiculaire refusé", [[axis_of(w.dir or 0) == axis_of(a.dir) then]], [[axis_of(w.dir or 0) ~= nil then]] },
  { "(e) chaîne rompue tue", [[if not (nx.x == fx and nx.y == fy) then bad[#bad + 1] = refusal("chaine_rompue", t, nil, item) end]], [[local _ = 0]] },
  { "tuiles propres lues comme monde", [[if own[tkey(x, y)] then return nil end]], [[local _ = 0]] },
  { "forbidden : tuile devant manquante", [[out[tkey(w.x + v[1], w.y + v[2])] = true]], [[out[tkey(w.x, w.y)] = true]] },
  { "forbidden : étranger oublié", [[if v and Pu.outputs(w) and Pu.foreign(w, item) and not (own and own[tkey(w.x, w.y)]) then]], [[if v and Pu.outputs(w) and not (own and own[tkey(w.x, w.y)]) then]] },
  { "queue : tuile de l'emprise prise pour une queue", [[if not occupied[k] and not (skip and skip[k]) then]], [[if not (skip and skip[k]) then]] },
  { "queue : tuile réservée prise pour une queue", [[if not occupied[k] and not (skip and skip[k]) then]], [[if not occupied[k] then]] },
  { "queue : même objet refusé", [[if w and Pu.foreign(w, item) then
        bad[#bad + 1] = refusal("pointe_vers_etranger", { x = ox + t.bx]], [[if w then
        bad[#bad + 1] = refusal("pointe_vers_etranger", { x = ox + t.bx]] },
  { "journal sans cause", [[(%s) objet %s contre %s en (%d, %d)", team and (team .. " ") or "", module, r.cause,]], [[(%s) objet %s contre %s en (%d, %d)", team and (team .. " ") or "", module, "?",]] },
}

do
  local survivors = 0
  for _, m in ipairs(MUTANTS) do
    local i, j = SRC:find(m[2], 1, true)
    if not i then
      total_fail = total_fail + 1
      print("ECHEC : mutant « " .. m[1] .. " » : motif introuvable dans le source (test à remettre à jour)")
    else
      local src2 = SRC:sub(1, i - 1) .. m[3] .. SRC:sub(j + 1)
      local ok, Pm = pcall(load_pu, src2)
      local caught
      if not ok then
        caught = true
      else
        local okb, bad_m = pcall(battery, Pm, false, M, Plan)
        caught = (not okb) or bad_m > 0
      end
      if caught then
        total_ok = total_ok + 1
      else
        total_fail = total_fail + 1
        survivors = survivors + 1
        print("ECHEC : mutant « " .. m[1] .. " » non vu par la batterie")
      end
    end
  end
end

print(string.format("[PURETE] BILAN : %d OK, %d ECHEC(S)", total_ok, total_fail))
os.exit(total_fail == 0 and 0 or 1)
